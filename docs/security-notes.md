# Notes de sécurité, limites et améliorations

## Hypothèses de confiance

- Odoo accepte l'identité du certificat **uniquement** parce qu'elle vient de Nginx. Il faut donc :
  - publier Odoo sur `127.0.0.1` seulement (`deploy/20-podman.sh`) ;
  - garder les `proxy_set_header X-SSL-Client-*` dans Nginx : ils écrasent toute valeur envoyée par le client.
- La clé privée de la CA (`pki/ca/ca.key`) ne doit jamais quitter la machine ni être montée dans un conteneur. En production : CA hors ligne ou HSM.

## Limites constatées

- Le TOTP est facultatif dans Odoo Community : chaque utilisateur l'active lui-même. Le certificat obligatoire compense en partie.
- Seul `POST /web/login` est contrôlé par le module. Une authentification par `/web/session/authenticate` (JSON-RPC) contourne le lien certificat ↔ compte, mais pas le mTLS de Nginx, qui reste exigé pour atteindre l'application.
- La validité de début (`notBefore`) et de fin (`notAfter`) est contrôlée par Nginx ; Odoo contrôle la date de fin enregistrée (`valid_until`), qui est une copie.
- Deux révocations indépendantes : CRL de la PKI et état dans Odoo. Révoquer dans l'une ne modifie pas l'autre.
- Les conteneurs sont lancés avec `--restart=always` ; pour un démarrage au boot sous systemd, utiliser des unités Quadlet.

## Améliorations proposées

- Rendre le TOTP obligatoire (contrôle supplémentaire dans le module).
- WebAuthn / FIDO2, résistant à l'hameçonnage.
- OCSP ou CRL automatique, état Odoo synchronisé avec la PKI.
- Contrôler aussi `/web/session/authenticate`.
- Renouvellement automatique des certificats.
