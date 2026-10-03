# -*- coding: utf-8 -*-
"""Lecture de l'identité X.509 transmise par Nginx.

IMPORTANT : ces en-têtes ne sont fiables que si Nginx les réécrit à chaque
requête (proxy_set_header) ET si Odoo n'est joignable que par Nginx
(publication sur 127.0.0.1). Voir nginx/odoo-mfa.conf.template.
"""
from odoo.http import request


def client_identity():
    headers = request.httprequest.headers
    return {
        'verify': headers.get('X-SSL-Client-Verify', ''),
        'subject': headers.get('X-SSL-Client-S-DN', ''),
        'issuer': headers.get('X-SSL-Client-I-DN', ''),
        'serial': headers.get('X-SSL-Client-Serial', ''),
        'fingerprint': headers.get('X-SSL-Client-Fingerprint', ''),
    }


def has_valid_mtls(identity):
    return identity['verify'] == 'SUCCESS' and bool(identity['serial'])
